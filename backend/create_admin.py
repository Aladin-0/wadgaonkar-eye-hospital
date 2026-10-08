import os
import django

def main():
    os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'wadgaonkar_backend.settings')
    django.setup()

    from django.contrib.auth.models import User
    if not User.objects.filter(username='admin').exists():
        User.objects.create_superuser('admin', 'admin@example.com', 'admin1234')
        print('Success! Created new superuser: admin / admin1234')
    else:
        u = User.objects.get(username='admin')
        u.set_password('admin1234')
        u.save()
        print('Success! Updated password for existing user: admin / admin1234')

if __name__ == '__main__':
    main()
