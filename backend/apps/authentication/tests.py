from datetime import timedelta
from unittest.mock import patch

from django.contrib.auth.models import User
from django.utils import timezone
from rest_framework.test import APITestCase

from apps.appointments.models import Appointment
from apps.authentication.models import PatientProfile


class DeleteAccountTests(APITestCase):
    SYNC = '/api/v1/auth/firebase-sync/'
    DELETE = '/api/v1/auth/delete-account/'

    def _login(self, uid='apple-uid-123'):
        r = self.client.post(self.SYNC, {
            'uid': uid, 'email': 'a@example.com', 'display_name': 'Test Patient',
            'mobile_number': '9999999999', 'age': 30,
        }, format='json')
        self.assertIn(r.status_code, (200, 201))
        return uid

    def test_requires_token(self):
        self._login()
        self.assertEqual(self.client.post(self.DELETE).status_code, 401)
        self.assertTrue(PatientProfile.objects.filter(uid='apple-uid-123').exists())

    @patch('firebase_admin.auth.verify_id_token', side_effect=Exception('bad'))
    def test_rejects_invalid_token(self, _):
        self._login()
        r = self.client.post(self.DELETE, HTTP_AUTHORIZATION='Bearer nope')
        self.assertEqual(r.status_code, 401)
        self.assertTrue(PatientProfile.objects.filter(uid='apple-uid-123').exists())

    @patch('firebase_admin.auth.delete_user')
    @patch('firebase_admin.auth.verify_id_token')
    def test_deletes_profile_and_anonymises_appointments(self, verify, delete_user):
        uid = self._login()
        verify.return_value = {'uid': uid}
        other = self._login('other-uid')
        now = timezone.now()
        for i, u in enumerate((uid, other)):
            Appointment.objects.create(
                appointment_code=f'C-{u}', patient_uid=u, patient_name='Test Patient',
                patient_mobile='9999999999', patient_id='WEH-1', doctor_id='d1',
                doctor_name='Dr X', doctor_specialization='Eye', service_id='s1',
                service_title='Eye Checkup', appointment_date=now.date(),
                slot_start_time=now + timedelta(hours=i), slot_end_time=now + timedelta(hours=i, minutes=15),
            )
        r = self.client.post(self.DELETE, HTTP_AUTHORIZATION='Bearer good')
        self.assertEqual(r.status_code, 200)
        self.assertFalse(PatientProfile.objects.filter(uid=uid).exists())
        self.assertFalse(User.objects.filter(username=uid).exists())
        # other users untouched
        self.assertTrue(PatientProfile.objects.filter(uid=other).exists())
        delete_user.assert_called_once_with(uid)

        anon = Appointment.objects.get(appointment_code=f'C-{uid}')
        self.assertEqual(anon.patient_name, 'Deleted User')
        self.assertEqual(anon.patient_mobile, '')
        self.assertNotEqual(anon.patient_uid, uid)
        kept = Appointment.objects.get(appointment_code=f'C-{other}')
        self.assertEqual(kept.patient_name, 'Test Patient')
