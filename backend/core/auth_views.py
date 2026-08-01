from django.conf import settings
from django.contrib import messages
from django.contrib.auth import login
from django.contrib.auth.decorators import login_required
from django.contrib.auth.models import User
from django.contrib.auth.views import LoginView
from django.shortcuts import redirect, render
from django.urls import reverse
from django.views.decorators.http import require_http_methods

from .access import membership_required
from .forms import TotpTokenForm
from .mfa import (
    confirm_device,
    get_or_create_pending_device,
    new_totp_secret,
    provisioning_uri,
    qr_data_url,
    user_has_confirmed_mfa,
    verify_totp,
)
from .models import TotpDevice
from .services import audit


class PasswordLoginView(LoginView):
    template_name = "registration/login.html"
    redirect_authenticated_user = True

    def dispatch(self, request, *args, **kwargs):
        if settings.TRUST_TAILSCALE_HEADERS:
            messages.info(request, "In diesem Betrieb ist der Tailscale-Zugang aktiv.")
            return redirect("access")
        return super().dispatch(request, *args, **kwargs)

    def form_valid(self, form):
        user = form.get_user()
        if user_has_confirmed_mfa(user):
            self.request.session["mfa_pending_user_id"] = user.pk
            self.request.session.pop("mfa_satisfied", None)
            return redirect("mfa_verify")
        login(self.request, user)
        self.request.session["mfa_satisfied"] = True
        return redirect(self.get_success_url())


@require_http_methods(["GET", "POST"])
def mfa_verify(request):
    user_id = request.session.get("mfa_pending_user_id")
    if not user_id:
        return redirect("login")
    user = User.objects.filter(pk=user_id, is_active=True).select_related("totp_device").first()
    if user is None or not user_has_confirmed_mfa(user):
        request.session.pop("mfa_pending_user_id", None)
        return redirect("login")

    form = TotpTokenForm(request.POST or None)
    if request.method == "POST" and form.is_valid():
        if verify_totp(user.totp_device.secret, form.cleaned_data["token"]):
            login(request, user, backend="django.contrib.auth.backends.ModelBackend")
            request.session.pop("mfa_pending_user_id", None)
            request.session["mfa_satisfied"] = True
            return redirect("access")
        form.add_error("token", "Der Code ist ungültig oder abgelaufen.")
    return render(request, "registration/mfa_verify.html", {"form": form})


@login_required
@membership_required()
@require_http_methods(["GET", "POST"])
def mfa_setup(request):
    if settings.TRUST_TAILSCALE_HEADERS:
        messages.info(request, "Bei Tailscale-Anmeldung ist TOTP nicht erforderlich.")
        return redirect("more")

    device = TotpDevice.objects.filter(user=request.user).first()
    if device and device.confirmed and request.method == "GET" and request.GET.get("neu") != "1":
        return render(request, "core/mfa_setup.html", {
            "confirmed": True,
            "form": TotpTokenForm(),
        })

    if request.GET.get("neu") == "1" or device is None:
        if device is None:
            device = TotpDevice(user=request.user)
        device.secret = new_totp_secret()
        device.confirmed = False
        device.confirmed_at = None
        device.save()
    elif not device.confirmed:
        pass
    else:
        device = get_or_create_pending_device(request.user)

    form = TotpTokenForm(request.POST or None)
    uri = provisioning_uri(request.user, device.secret)
    if request.method == "POST" and form.is_valid():
        if verify_totp(device.secret, form.cleaned_data["token"]):
            confirm_device(device)
            request.session["mfa_satisfied"] = True
            audit(request.user, request.membership.station, "mfa.enabled", device, {
                "fields": ["confirmed"]
            })
            messages.success(request, "Zwei-Faktor-Authentifizierung wurde aktiviert.")
            return redirect("mfa_setup")
        form.add_error("token", "Der Code ist ungültig. Bitte erneut versuchen.")

    return render(request, "core/mfa_setup.html", {
        "confirmed": False,
        "form": form,
        "secret": device.secret,
        "qr_data_url": qr_data_url(uri),
        "provisioning_uri": uri,
    })


@login_required
@membership_required()
@require_http_methods(["POST"])
def mfa_disable(request):
    if settings.TRUST_TAILSCALE_HEADERS:
        return redirect("more")
    device = TotpDevice.objects.filter(user=request.user, confirmed=True).first()
    if device:
        audit(request.user, request.membership.station, "mfa.disabled", device, {
            "fields": ["confirmed"]
        })
        device.delete()
        messages.success(request, "Zwei-Faktor-Authentifizierung wurde deaktiviert.")
    return redirect(reverse("mfa_setup"))
