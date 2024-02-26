#!/bin/bash

useradd testPam
chpasswd  << EOF
testPam:myPwdTest
EOF

echo "pam user added"