from django.http import JsonResponse
from django.utils import timezone
from django.views.decorators.http import require_GET

from .access import CONTENT_ROLES, membership_required
from .models import CalendarEvent, HandoverEntry
from .views import prioritized_handovers


def _user_payload(user):
    return {
        "username": user.username,
        "display_name": user.first_name or user.username,
    }


def _handover_payload(item):
    return {
        "id": item.pk,
        "title": item.title,
        "category": item.category,
        "category_label": item.get_category_display(),
        "priority": item.priority,
        "priority_label": item.get_priority_display(),
        "status": item.status,
        "status_label": item.get_status_display(),
        "updated_at": item.updated_at.isoformat(),
        "version": item.version,
    }


@require_GET
@membership_required(CONTENT_ROLES)
def api_me(request):
    membership = request.membership
    return JsonResponse({
        "user": _user_payload(request.user),
        "station": {
            "name": membership.station.name,
            "slug": membership.station.slug,
            "calendar_enabled": membership.station.calendar_enabled,
            "birthdays_enabled": membership.station.birthdays_enabled,
            "coffee_enabled": membership.station.coffee_enabled,
            "feeds_enabled": membership.station.feeds_enabled,
        },
        "role": membership.role,
        "role_label": membership.get_role_display(),
    })


@require_GET
@membership_required(CONTENT_ROLES)
def api_dashboard(request):
    station = request.membership.station
    active = prioritized_handovers(station)
    events = []
    if station.calendar_enabled:
        events = [
            {
                "id": event.pk,
                "title": event.title,
                "starts_at": event.starts_at.isoformat(),
                "ends_at": event.ends_at.isoformat(),
            }
            for event in CalendarEvent.objects.filter(
                station=station,
                ends_at__gte=timezone.now(),
                cancelled_at__isnull=True,
            ).order_by("starts_at")[:3]
        ]
    handovers = [_handover_payload(item) for item in active[:10]]
    return JsonResponse({
        "open_count": active.count(),
        "urgent_count": active.filter(priority=HandoverEntry.Priority.URGENT).count(),
        "handovers": handovers,
        "events": events,
    })


@require_GET
@membership_required(CONTENT_ROLES)
def api_handovers(request):
    scope = request.GET.get("ansicht", "aktiv")
    station = request.membership.station
    if scope == "archiv":
        qs = HandoverEntry.objects.filter(
            station=station, status=HandoverEntry.Status.DONE
        ).order_by("-completed_at", "-updated_at")
    else:
        qs = prioritized_handovers(station)
        if scope == "dringend":
            qs = qs.filter(priority=HandoverEntry.Priority.URGENT)
    items = [_handover_payload(item) for item in qs[:50]]
    return JsonResponse({"scope": scope, "results": items})
