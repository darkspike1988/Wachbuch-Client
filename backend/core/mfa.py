import base64
import io

import pyotp
from django.conf import settings
from django.utils import timezone

from .models import TotpDevice


def new_totp_secret():
    return pyotp.random_base32()


def provisioning_uri(user, secret):
    return pyotp.TOTP(secret).provisioning_uri(
        name=user.username,
        issuer_name=settings.MFA_ISSUER_NAME,
    )


def verify_totp(secret, token):
    token = (token or "").strip().replace(" ", "")
    if not token.isdigit():
        return False
    return pyotp.TOTP(secret).verify(token, valid_window=1)


def qr_data_url(uri):
    import segno

    buffer = io.BytesIO()
    segno.make(uri, error="m").save(buffer, kind="png", scale=6)
    encoded = base64.b64encode(buffer.getvalue()).decode("ascii")
    return f"data:image/png;base64,{encoded}"


def user_has_confirmed_mfa(user):
    return TotpDevice.objects.filter(user=user, confirmed=True).exists()


def confirm_device(device):
    device.confirmed = True
    device.confirmed_at = timezone.now()
    device.save(update_fields=["confirmed", "confirmed_at"])


def get_or_create_pending_device(user):
    device = TotpDevice.objects.filter(user=user).first()
    if device is None:
        return TotpDevice.objects.create(user=user, secret=new_totp_secret())
    if not device.confirmed:
        return device
    device.secret = new_totp_secret()
    device.confirmed = False
    device.confirmed_at = None
    device.save(update_fields=["secret", "confirmed", "confirmed_at"])
    return device
