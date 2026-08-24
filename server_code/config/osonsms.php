<?php

return [
    /*
    |--------------------------------------------------------------------------
    | OsonSMS
    |--------------------------------------------------------------------------
    | Документация: https://osonsms.com/docs/sms-api-documentation.pdf
    | Не коммитьте реальный SMS_TOKEN в git — только в .env на сервере.
    */
    'login' => env('SMS_LOGIN', 'ssboss'),
    'token' => env('SMS_TOKEN', ''),
    'sender' => env('SMS_SENDER', 'SSBOSS'),
    'server' => env('SMS_SERVER', 'https://api.osonsms.com/sendsms_v1.php'),
    'otp_ttl_seconds' => (int) env('SMS_OTP_TTL', 300),
    'otp_length' => (int) env('SMS_OTP_LENGTH', 4),
    'otp_resend_seconds' => (int) env('SMS_OTP_RESEND', 60),
];
