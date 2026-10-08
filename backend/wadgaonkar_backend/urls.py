"""
Root URL Configuration for Wadgaonkar Eye Hospital Backend.
"""
from django.contrib import admin
from django.urls import path, include
from django.http import JsonResponse, HttpResponse

from rest_framework_simplejwt.views import TokenObtainPairView

def api_health_check(request):
    return JsonResponse({
        'hospital': 'Wadgaonkar Eye Hospital',
        'status': 'operational',
        'api_version': 'v1',
        'timestamp': '2026-08-05T22:15:00',
    })

def privacy_policy_view(request):
    html = """
    <html>
    <head>
        <title>Privacy Policy - Wadgaonkar Eye Hospital</title>
        <style>
            body { font-family: sans-serif; line-height: 1.6; max-width: 800px; margin: 40px auto; padding: 20px; color: #333; }
            h1, h2 { color: #0056b3; }
        </style>
    </head>
    <body>
        <h1>Privacy Policy</h1>
        <p><strong>Last Updated:</strong> September 3, 2026</p>
        <p>Welcome to the Wadgaonkar Eye Hospital Patient Application ("App"). This Privacy Policy explains how Wadgaonkar Eye Hospital ("we", "us", or "our") collects, uses, shares, and protects your personal and sensitive information when you use our App and services.</p>
        <p>We are committed to protecting your privacy and ensuring compliance with the Digital Personal Data Protection (DPDP) Act of India and the guidelines set forth by the Google Play Store.</p>
        
        <h2>1. Information We Collect</h2>
        <ul>
            <li><strong>Personal Information:</strong> Name, age, gender, and contact details (mobile number, email address) provided during registration.</li>
            <li><strong>Authentication Data:</strong> We use Firebase Authentication and Google Sign-In to securely verify your identity.</li>
            <li><strong>Health Information:</strong> Information regarding your appointments, selected services (e.g., eye checkup), and past booking history to determine discount eligibility.</li>
            <li><strong>Device Information:</strong> Basic device identifiers necessary for crash reporting and sending appointment reminder push notifications.</li>
        </ul>
        
        <h2>2. How We Use Your Information</h2>
        <ul>
            <li>To schedule, manage, and track your OPD (Outpatient Department) appointments.</li>
            <li>To process pre-paid online payments securely via the Razorpay Payment Gateway.</li>
            <li>To send you automated reminders (via push notifications) prior to your scheduled slot.</li>
            <li>To calculate and apply appropriate patient discounts automatically.</li>
            <li>To maintain a digital medical record of your visits at Wadgaonkar Eye Hospital.</li>
        </ul>

        <h2>3. How We Share Your Information</h2>
        <p>We <strong>do not</strong> sell, rent, or trade your personal or health data to any third parties for marketing or advertising purposes. Your information is only shared with:</p>
        <ul>
            <li><strong>Payment Gateways (Razorpay):</strong> To securely process your digital payments. We do not store your UPI PIN or banking passwords.</li>
            <li><strong>Backend Infrastructure:</strong> For secure database storage and user authentication.</li>
            <li><strong>Legal Authorities:</strong> Only if strictly required by Indian law or a valid court order.</li>
        </ul>

        <h2>4. Data Security</h2>
        <p>We implement robust security measures, including HTTPS encryption and secure token-based API authentication, to protect your data against unauthorized access, alteration, or destruction.</p>
        
        <h2>5. Account and Data Deletion</h2>
        <p>You have the right to request the deletion of your account and associated personal data. To do so, please contact our support team using the details provided below. Upon verification, your digital account will be deleted, subject to medical record retention laws mandated by the Government of India.</p>

        <h2>6. Contact Us</h2>
        <p>If you have any questions or concerns regarding this Privacy Policy or your data, please contact us at:</p>
        <ul>
            <li><strong>Email:</strong> wadgaonkareyeehospital@gmail.com</li>
            <li><strong>Phone:</strong> 02402324219</li>
            <li><strong>Address:</strong> 126, Madhushri, Varad Ganesh Mandir Rd, Samarth Nagar, Chhatrapati Sambhajinagar, Maharashtra 431001</li>
        </ul>
    </body>
    </html>
    """
    return HttpResponse(html)

urlpatterns = [
    path('admin/', admin.site.urls),
    path('privacy/', privacy_policy_view, name='privacy-policy'),
    path('api/health/', api_health_check, name='api-health'),
    path('api/v1/auth/admin/login/', TokenObtainPairView.as_view(), name='token_obtain_pair'),
    path('api/v1/auth/', include('apps.authentication.urls')),
    path('api/v1/doctors/', include('apps.doctors.urls')),
    path('api/v1/services/', include('apps.services.urls')),
    path('api/v1/appointments/', include('apps.appointments.urls')),
    path('api/v1/payments/', include('apps.payments.urls')),
]

# Customize Admin Site Headers
admin.site.site_header = "Wadgaonkar Eye Hospital OPD Administration"
admin.site.site_title = "WEH Portal"
admin.site.index_title = "Hospital Clinical Management System"
