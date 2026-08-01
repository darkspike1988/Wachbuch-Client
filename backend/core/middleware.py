import ipaddress

from django.conf import settings
from django.contrib.auth import login, logout
from django.contrib.auth.models import User
from django.http import HttpResponseNotFound

from .models import Membership, Station


def _client_ip(request):
    raw = (request.META.get("REMOTE_ADDR") or "").strip()
    if not raw:
        return None
    try:
        return ipaddress.ip_address(raw)
    except ValueError:
        return None


def request_from_trusted_proxy(request):
    """Tailscale identity headers are only trusted from configured proxy CIDRs."""
    client_ip = _client_ip(request)
    if client_ip is None:
        return False
    for network in settings.TRUSTED_PROXY_NETWORKS:
        if client_ip in network:
            return True
    return False


_INTERNAL_NETWORKS = (
    ipaddress.ip_network("10.0.0.0/8"),
    ipaddress.ip_network("172.16.0.0/12"),
    ipaddress.ip_network("192.168.0.0/16"),
    ipaddress.ip_network("fc00::/7"),
)


def request_from_private_network(request):
    """Allow health probes only from loopback/link-local/RFC1918/ULA."""
    client_ip = _client_ip(request)
    if client_ip is None:
        return False
    if client_ip.is_loopback or client_ip.is_link_local:
        return True
    return any(client_ip in network for network in _INTERNAL_NETWORKS)


class TailscaleAuthMiddleware:
    """Use identity headers injected by the loopback-only Tailscale proxy."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if settings.TRUST_TAILSCALE_HEADERS:
            if not request_from_trusted_proxy(request):
                if request.user.is_authenticated:
                    logout(request)
                return self.get_response(request)
            login_name = request.META.get("HTTP_TAILSCALE_USER_LOGIN", "").strip().lower()
            display_name = request.META.get("HTTP_TAILSCALE_USER_NAME", "").strip()
            if not login_name:
                if request.user.is_authenticated:
                    logout(request)
                return self.get_response(request)
            if request.user.is_authenticated and request.user.username != login_name:
                logout(request)
            if not request.user.is_authenticated:
                user, _ = User.objects.get_or_create(
                    username=login_name,
                    defaults={"email": login_name, "first_name": display_name[:150]},
                )
                if not user.is_active:
                    return self.get_response(request)
                if display_name and user.first_name != display_name[:150]:
                    user.first_name = display_name[:150]
                    user.save(update_fields=["first_name"])
                if login_name == settings.TAILSCALE_ADMIN_LOGIN:
                    self._ensure_admin(user)
                login(request, user, backend="django.contrib.auth.backends.ModelBackend")
                request.session.pop("mfa_pending_user_id", None)
                request.session["mfa_satisfied"] = True
        return self.get_response(request)

    @staticmethod
    def _ensure_admin(user):
        membership = user.station_memberships.filter(is_active=True).select_related(
            "station"
        ).first()
        if membership:
            station = membership.station
        else:
            station = Station.get_default()
        Membership.objects.update_or_create(
            user=user,
            station=station,
            defaults={"role": Membership.Role.ADMIN, "is_active": True},
        )


class SecurityHeadersMiddleware:
    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        response = self.get_response(request)
        response.headers["Content-Security-Policy"] = (
            "default-src 'self'; img-src 'self' data:; style-src 'self'; "
            "script-src 'self'; font-src 'self'; connect-src 'self'; "
            "frame-ancestors 'none'; base-uri 'self'; form-action 'self'"
        )
        response.headers["Permissions-Policy"] = (
            "camera=(), microphone=(), geolocation=(), payment=(), usb=()"
        )
        return response


class PrivateHealthzMiddleware:
    """Hide /healthz/ from non-private clients to reduce reconnaissance surface."""

    def __init__(self, get_response):
        self.get_response = get_response

    def __call__(self, request):
        if request.path == "/healthz/" and not request_from_private_network(request):
            return HttpResponseNotFound()
        return self.get_response(request)
