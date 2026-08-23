# Wadgaonkar Eye Hospital - Django Backend

## Local Database Setup (PostgreSQL)

The backend uses PostgreSQL for robust data integrity and locking mechanisms. Follow these steps to set up the local database:

1. Ensure PostgreSQL is installed and running on your system.
2. Open the PostgreSQL interactive terminal:
   ```bash
   sudo -u postgres psql
   ```
3. Create the database and user:
   ```sql
   CREATE DATABASE weh_db;
   CREATE USER postgres WITH PASSWORD 'postgres';
   ALTER ROLE postgres SET client_encoding TO 'utf8';
   ALTER ROLE postgres SET default_transaction_isolation TO 'read committed';
   ALTER ROLE postgres SET timezone TO 'UTC';
   GRANT ALL PRIVILEGES ON DATABASE weh_db TO postgres;
   ALTER DATABASE weh_db OWNER TO postgres;
   \q
   ```
4. Run migrations:
   ```bash
   python3 manage.py migrate
   ```

## Running the Application

### Django Dev Server
```bash
python3 manage.py runserver
```

### Celery Worker (Phase 4 - Background Tasks)
In a separate terminal:
```bash
celery -A wadgaonkar_backend worker --loglevel=info
```

### Celery Beat Scheduler (Periodic Tasks)
In another terminal:
```bash
celery -A wadgaonkar_backend beat --loglevel=info
```

This schedules the following automatically (via `settings.py` CELERY_BEAT_SCHEDULE):
- **Every minute**: Transition confirmed → gracePeriod when slot time is past; expire gracePeriod → expired after 45 min
- **Every minute**: Expire `pendingPayment` slots older than 5 minutes
- **Every 5 minutes**: Send FCM late-arrival push notifications at 10/20/30/40-min marks

### Required Environment Variables
```bash
export CELERY_BROKER_URL=redis://localhost:6379/0
export CELERY_RESULT_BACKEND=redis://localhost:6379/0
export DB_NAME=weh_db
export DB_USER=postgres
export DB_PASSWORD=<your_password>
export GRACE_PERIOD_MINUTES=45  # Optional, defaults to 45
```

## Running Tests
```bash
DJANGO_SETTINGS_MODULE=wadgaonkar_backend.settings_test python3 -m pytest apps/appointments/tests.py -v
```

Tests use SQLite in-memory (no PostgreSQL needed for CI/CD).

