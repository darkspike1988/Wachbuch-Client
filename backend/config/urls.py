from django.contrib import admin
from django.urls import include, path

from core.auth_views import PasswordLoginView, mfa_verify
from core.views import healthz
from django.contrib.auth import views as auth_views


urlpatterns = [
    path("healthz/", healthz, name="healthz"),
    path("anmelden/", PasswordLoginView.as_view(), name="login"),
    path("anmelden/mfa/", mfa_verify, name="mfa_verify"),
    path("abmelden/", auth_views.LogoutView.as_view(), name="logout"),
    path("django-admin/", admin.site.urls),
    path("", include("core.urls")),
]
