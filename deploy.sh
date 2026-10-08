#!/bin/bash
set -e

echo "Building Flutter AAB..."
cd "apps/patient_app"
/home/aladin/flutter/bin/flutter build appbundle --release
cd ../..

echo "Compressing backend..."
rm -f backend_deploy.tar.gz
tar -czvf backend_deploy.tar.gz backend/

echo "Uploading to VPS..."
sshpass -p 'kutub@708' scp -o StrictHostKeyChecking=no -P 2222 backend_deploy.tar.gz techverse@182.70.63.4:/home/techverse/wadgaonkar_eye_hospital/

echo "Extracting and restarting backend on VPS..."
sshpass -p 'kutub@708' ssh -o StrictHostKeyChecking=no -p 2222 techverse@182.70.63.4 << 'EOF'
  cd /home/techverse/wadgaonkar_eye_hospital/
  tar -xzvf backend_deploy.tar.gz
  cd backend
  docker compose build
  docker compose down
  docker compose up -d
  docker ps | grep backend
EOF

echo "Deployment complete."
