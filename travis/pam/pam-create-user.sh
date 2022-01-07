#!/bin/bash

useradd testPam
chpasswd  << EOF
testPam:myPwd
EOF

echo "pam user added"