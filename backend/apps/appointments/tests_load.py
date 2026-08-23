import pytest
import threading
from django.utils import timezone
from datetime import timedelta
from rest_framework.test import APIClient
from apps.doctors.models import Doctor
from apps.appointments.models import Appointment
from django.db import connection

@pytest.fixture
def test_doctor(db):
    return Doctor.objects.create(
        id="doc_stress",
        name="Dr. Stress",
        specialization="General",
        consultation_fee=300,
        slot_duration_minutes=15,
        working_days=[1, 2, 3, 4, 5, 6, 7],
        shift_start_time="09:00",
        shift_end_time="17:00",
        is_active=True
    )

@pytest.mark.django_db(transaction=True)
def test_concurrency_double_booking(test_doctor):
    """
    Simulate 50 concurrent requests trying to book the exact same slot.
    Only 1 should succeed due to database row locking in views.py `select_for_update()`.
    Using threading to generate simultaneous requests.
    """
    target_date = (timezone.now() + timedelta(days=5)).date()
    target_time = "10:00:00"
    slot_datetime = timezone.make_aware(timezone.datetime.strptime(f"{target_date} {target_time}", "%Y-%m-%d %H:%M:%S"))
    
    num_threads = 50
    results = []
    
    def book_slot(thread_id):
        # Must close existing connections to ensure each thread gets a separate DB connection
        # to effectively simulate parallel HTTP requests locking rows.
        connection.close()
        client = APIClient()
        response = client.post('/api/v1/appointments/', {
            "patient_uid": f"user_{thread_id}",
            "patient_name": f"Stress Tester {thread_id}",
            "patient_mobile": "9999999999",
            "patient_id": f"WEH-{thread_id}",
            "doctor_id": test_doctor.id,
            "doctor_name": test_doctor.name,
            "doctor_specialization": test_doctor.specialization,
            "service_id": "srv1",
            "service_title": "Checkup",
            "appointment_date": str(target_date),
            "slot_start_time": slot_datetime.isoformat(),
            "consultation_fee": "300.00"
        }, format='json')
        results.append(response.status_code)
        connection.close()
        
    threads = []
    for i in range(num_threads):
        t = threading.Thread(target=book_slot, args=(i,))
        threads.append(t)
        
    for t in threads:
        t.start()
        
    for t in threads:
        t.join()
        
    success_count = results.count(201)
    conflict_count = results.count(409)
    
    # We assert that exactly ONE appointment was created, and all others received 409 Conflict.
    assert success_count == 1
    assert conflict_count == num_threads - 1
    
    # Double check database state
    appts = Appointment.objects.filter(doctor_id=test_doctor.id, appointment_date=target_date, slot_start_time=slot_datetime)
    assert appts.count() == 1
