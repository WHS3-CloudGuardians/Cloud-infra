from unittest import mock
from uuid import uuid4

from prowler.providers.azure.services.defender.defender_service import SecurityContacts
from tests.providers.azure.azure_fixtures import (
    AZURE_SUBSCRIPTION_ID,
    set_mocked_azure_provider,
)


class Test_defender_ensure_notify_alerts_severity_is_high:
    def test_defender_no_subscriptions(self):
        defender_client = mock.MagicMock
        defender_client.security_contacts = {}

        with (
            mock.patch(
                "prowler.providers.common.provider.Provider.get_global_provider",
                return_value=set_mocked_azure_provider(),
            ),
            mock.patch(
                "prowler.providers.azure.services.defender.defender_ensure_notify_alerts_severity_is_high.defender_ensure_notify_alerts_severity_is_high.defender_client",
                new=defender_client,
            ),
        ):
            from prowler.providers.azure.services.defender.defender_ensure_notify_alerts_severity_is_high.defender_ensure_notify_alerts_severity_is_high import (
                defender_ensure_notify_alerts_severity_is_high,
            )

            check = defender_ensure_notify_alerts_severity_is_high()
            result = check.execute()
            assert len(result) == 0

    def test_defender_severity_alerts_critical(self):
        resource_id = str(uuid4())
        defender_client = mock.MagicMock
        defender_client.security_contacts = {
            AZURE_SUBSCRIPTION_ID: {
                resource_id: SecurityContacts(
                    resource_id=resource_id,
                    name="default",
                    emails="",
                    phone="",
                    alert_notifications_minimal_severity="Critical",
                    alert_notifications_state="On",
                    notified_roles=["Contributor"],
                    notified_roles_state="On",
                )
            }
        }

        with (
            mock.patch(
                "prowler.providers.common.provider.Provider.get_global_provider",
                return_value=set_mocked_azure_provider(),
            ),
            mock.patch(
                "prowler.providers.azure.services.defender.defender_ensure_notify_alerts_severity_is_high.defender_ensure_notify_alerts_severity_is_high.defender_client",
                new=defender_client,
            ),
        ):
            from prowler.providers.azure.services.defender.defender_ensure_notify_alerts_severity_is_high.defender_ensure_notify_alerts_severity_is_high import (
                defender_ensure_notify_alerts_severity_is_high,
            )

            check = defender_ensure_notify_alerts_severity_is_high()
            result = check.execute()
            assert len(result) == 1
            assert result[0].status == "FAIL"
            assert (
                result[0].status_extended
                == f"Notifications are not enabled for alerts with a minimum severity of high or lower in subscription {AZURE_SUBSCRIPTION_ID}."
            )
            assert result[0].subscription == AZURE_SUBSCRIPTION_ID
            assert result[0].resource_name == "default"
            assert result[0].resource_id == resource_id

    def test_defender_severity_alerts_high(self):
        resource_id = str(uuid4())
        defender_client = mock.MagicMock
        defender_client.security_contacts = {
            AZURE_SUBSCRIPTION_ID: {
                resource_id: SecurityContacts(
                    resource_id=resource_id,
                    name="default",
                    emails="",
                    phone="",
                    alert_notifications_minimal_severity="High",
                    alert_notifications_state="On",
                    notified_roles=["Contributor"],
                    notified_roles_state="On",
                )
            }
        }

        with (
            mock.patch(
                "prowler.providers.common.provider.Provider.get_global_provider",
                return_value=set_mocked_azure_provider(),
            ),
            mock.patch(
                "prowler.providers.azure.services.defender.defender_ensure_notify_alerts_severity_is_high.defender_ensure_notify_alerts_severity_is_high.defender_client",
                new=defender_client,
            ),
        ):
            from prowler.providers.azure.services.defender.defender_ensure_notify_alerts_severity_is_high.defender_ensure_notify_alerts_severity_is_high import (
                defender_ensure_notify_alerts_severity_is_high,
            )

            check = defender_ensure_notify_alerts_severity_is_high()
            result = check.execute()
            assert len(result) == 1
            assert result[0].status == "PASS"
            assert (
                result[0].status_extended
                == f"Notifications are enabled for alerts with a minimum severity of high or lower (High) in subscription {AZURE_SUBSCRIPTION_ID}."
            )
            assert result[0].subscription == AZURE_SUBSCRIPTION_ID
            assert result[0].resource_name == "default"
            assert result[0].resource_id == resource_id

    def test_defender_severity_alerts_low(self):
        resource_id = str(uuid4())
        defender_client = mock.MagicMock
        defender_client.security_contacts = {
            AZURE_SUBSCRIPTION_ID: {
                resource_id: SecurityContacts(
                    resource_id=resource_id,
                    name="default",
                    emails="",
                    phone="",
                    alert_notifications_minimal_severity="Low",
                    alert_notifications_state="On",
                    notified_roles=["Contributor"],
                    notified_roles_state="On",
                )
            }
        }

        with (
            mock.patch(
                "prowler.providers.common.provider.Provider.get_global_provider",
                return_value=set_mocked_azure_provider(),
            ),
            mock.patch(
                "prowler.providers.azure.services.defender.defender_ensure_notify_alerts_severity_is_high.defender_ensure_notify_alerts_severity_is_high.defender_client",
                new=defender_client,
            ),
        ):
            from prowler.providers.azure.services.defender.defender_ensure_notify_alerts_severity_is_high.defender_ensure_notify_alerts_severity_is_high import (
                defender_ensure_notify_alerts_severity_is_high,
            )

            check = defender_ensure_notify_alerts_severity_is_high()
            result = check.execute()
            assert len(result) == 1
            assert result[0].status == "PASS"
            assert (
                result[0].status_extended
                == f"Notifications are enabled for alerts with a minimum severity of high or lower (Low) in subscription {AZURE_SUBSCRIPTION_ID}."
            )
            assert result[0].subscription == AZURE_SUBSCRIPTION_ID
            assert result[0].resource_name == "default"
            assert result[0].resource_id == resource_id

    def test_defender_default_security_contact_not_found(self):
        defender_client = mock.MagicMock
        defender_client.security_contacts = {
            AZURE_SUBSCRIPTION_ID: {
                f"/subscriptions/{AZURE_SUBSCRIPTION_ID}/providers/Microsoft.Security/securityContacts/default": SecurityContacts(
                    resource_id=f"/subscriptions/{AZURE_SUBSCRIPTION_ID}/providers/Microsoft.Security/securityContacts/default",
                    name="default",
                    emails="",
                    phone="",
                    alert_notifications_minimal_severity="",
                    alert_notifications_state="",
                    notified_roles=[""],
                    notified_roles_state="",
                )
            }
        }

        with (
            mock.patch(
                "prowler.providers.common.provider.Provider.get_global_provider",
                return_value=set_mocked_azure_provider(),
            ),
            mock.patch(
                "prowler.providers.azure.services.defender.defender_ensure_notify_alerts_severity_is_high.defender_ensure_notify_alerts_severity_is_high.defender_client",
                new=defender_client,
            ),
        ):
            from prowler.providers.azure.services.defender.defender_ensure_notify_alerts_severity_is_high.defender_ensure_notify_alerts_severity_is_high import (
                defender_ensure_notify_alerts_severity_is_high,
            )

            check = defender_ensure_notify_alerts_severity_is_high()
            result = check.execute()
            assert len(result) == 1
            assert result[0].status == "FAIL"
            assert (
                result[0].status_extended
                == f"Notifications are not enabled for alerts with a minimum severity of high or lower in subscription {AZURE_SUBSCRIPTION_ID}."
            )
            assert result[0].subscription == AZURE_SUBSCRIPTION_ID
            assert result[0].resource_name == "default"
            assert (
                result[0].resource_id
                == f"/subscriptions/{AZURE_SUBSCRIPTION_ID}/providers/Microsoft.Security/securityContacts/default"
            )

    def test_defender_default_security_contact_not_found_empty_name(self):
        resource_id = f"/subscriptions/{AZURE_SUBSCRIPTION_ID}/providers/Microsoft.Security/securityContacts/default"
        defender_client = mock.MagicMock
        defender_client.security_contacts = {
            AZURE_SUBSCRIPTION_ID: {
                resource_id: SecurityContacts(
                    resource_id=resource_id,
                    name="",
                    emails="",
                    phone="",
                    alert_notifications_minimal_severity="",
                    alert_notifications_state="",
                    notified_roles=[""],
                    notified_roles_state="",
                )
            }
        }

        contact = defender_client.security_contacts[AZURE_SUBSCRIPTION_ID][resource_id]
        contact.name = getattr(contact, "name", "default") or "default"

        with (
            mock.patch(
                "prowler.providers.common.provider.Provider.get_global_provider",
                return_value=set_mocked_azure_provider(),
            ),
            mock.patch(
                "prowler.providers.azure.services.defender.defender_ensure_notify_alerts_severity_is_high.defender_ensure_notify_alerts_severity_is_high.defender_client",
                new=defender_client,
            ),
        ):
            from prowler.providers.azure.services.defender.defender_ensure_notify_alerts_severity_is_high.defender_ensure_notify_alerts_severity_is_high import (
                defender_ensure_notify_alerts_severity_is_high,
            )

            check = defender_ensure_notify_alerts_severity_is_high()
            result = check.execute()
            assert len(result) == 1
            assert result[0].status == "FAIL"
            assert (
                result[0].status_extended
                == f"Notifications are not enabled for alerts with a minimum severity of high or lower in subscription {AZURE_SUBSCRIPTION_ID}."
            )
            assert result[0].subscription == AZURE_SUBSCRIPTION_ID
            assert result[0].resource_name == "default"
            assert result[0].resource_id == resource_id
