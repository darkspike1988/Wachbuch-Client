from datetime import timedelta

from django.conf import settings
from django.core.management.base import BaseCommand
from django.db import connection
from django.utils import timezone

from core.models import AuditEvent, CalendarEvent, FeedItem, HandoverEntry


class Command(BaseCommand):
    help = "Löscht abgelaufene Fachdaten gemäß RETENTION_*-Einstellungen."

    def add_arguments(self, parser):
        parser.add_argument(
            "--dry-run",
            action="store_true",
            help="Nur zählen, nichts löschen.",
        )

    def handle(self, *args, **options):
        dry_run = options["dry_run"]
        now = timezone.now()
        handover_qs = HandoverEntry.objects.filter(
            status=HandoverEntry.Status.DONE,
            completed_at__lt=now - timedelta(days=settings.RETENTION_HANDOVER_DAYS),
        )
        calendar_qs = CalendarEvent.objects.filter(
            ends_at__lt=now - timedelta(days=settings.RETENTION_CALENDAR_DAYS),
        )
        feed_qs = FeedItem.objects.filter(
            imported_at__lt=now - timedelta(days=settings.RETENTION_FEED_DAYS),
        )
        audit_qs = AuditEvent.objects.filter(
            created_at__lt=now - timedelta(days=settings.RETENTION_AUDIT_DAYS),
        )

        self.stdout.write(f"Erledigte Übergaben: {handover_qs.count()}")
        self.stdout.write(f"Abgelaufene Kalendertermine: {calendar_qs.count()}")
        self.stdout.write(f"Alte Feed-Einträge: {feed_qs.count()}")
        self.stdout.write(f"Alte Audit-Ereignisse: {audit_qs.count()}")

        if dry_run:
            self.stdout.write(self.style.SUCCESS("Dry-run abgeschlossen."))
            return

        handover_ids = list(handover_qs.values_list("pk", flat=True))
        audit_ids = list(audit_qs.values_list("pk", flat=True))

        with connection.cursor() as cursor:
            if handover_ids:
                cursor.execute(
                    "DELETE FROM core_handoverrevision WHERE handover_id = ANY(%s)",
                    [handover_ids],
                )
                cursor.execute(
                    "DELETE FROM core_handoverentry WHERE id = ANY(%s)",
                    [handover_ids],
                )
            if audit_ids:
                cursor.execute(
                    "DELETE FROM core_auditevent WHERE id = ANY(%s)",
                    [audit_ids],
                )

        calendar_qs.delete()
        feed_qs.delete()
        self.stdout.write(self.style.SUCCESS("Retention-Lauf abgeschlossen."))
