import pytest
from rest_framework.test import APIClient
from rest_framework import status
from django.urls import reverse
from apps.doctors.models import Doctor
from apps.appointments.models import Appointment
from django.utils import timezone
from datetime import timedelta
import concurrent.futures

@pytest.fixture
def doctor_for_concurrency(db):
    return Doctor.objects.create(
        id="doc_conc",
        name="Dr. Concurrency",
        specialization="General",
        consultation_fee=300,
        slot_duration_minutes=15,
        working_days=[1, 2, 3, 4, 5, 6, 7],
        shift_start_time="09:00",
        shift_end_time="17:00",
        is_active=True
    )

@pytest.mark.django_db(transaction=True)
def test_appointment_booking_concurrency(doctor_for_concurrency, live_server):
    # To truly test concurrency in Django tests using threading, we might need TransactionTestCase
    # or the live_server fixture which runs a real server thread, allowing simultaneous requests.
    
    client = APIClient()
    
    # We will try to book the same slot 10 times simultaneously
    target_date = (timezone.now() + timedelta(days=1)).date().isoformat()
    target_time = "10:00:00"
    
    url = '/api/v1/appointments/'
    
    def attempt_booking(i):
        # Different APIClient for each thread just to be safe
        thread_client = APIClient()
        response = thread_client.post(url, {
            'patient_uid': f"uid_{i}",
            'patient_name': f"Patient {i}",
            'patient_mobile': f"99900011{i:02d}",
            'patient_id': f"pid_{i}",
            'doctor_id': doctor_for_concurrency.id,
            'doctor_name': doctor_for_concurrency.name,
            'doctor_specialization': doctor_for_concurrency.specialization,
            'service_id': "srv_conc",
            'service_title': "General Checkup",
            'appointment_date': target_date,
            'slot_start_time': f"{target_date}T{target_time}Z",
            'slot_end_time': f"{target_date}T10:15:00Z",
            'consultation_fee': doctor_for_concurrency.consultation_fee
        }, format='json')
        return response.status_code

    with concurrent.futures.ThreadPoolExecutor(max_workers=10) as executor:
        results = list(executor.map(attempt_booking, range(10)))
        # Only one should succeed (either 200 or 201)
        successes = [r for r in results if r in (status.HTTP_200_OK, status.HTTP_201_CREATED)]
        
        assert len(successes) == 1, f"Expected exactly 1 success, got {len(successes)}. Results: {results}"
        assert len(results) - len(successes) == 9, f"Expected 9 rejections, got {len(results) - len(successes)}"
