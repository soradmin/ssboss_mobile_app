<?php

namespace App\Models;

use Illuminate\Contracts\Auth\MustVerifyEmail;
use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Passport\HasApiTokens;

class User extends Authenticatable
{
    use HasFactory, Notifiable, HasApiTokens;

    /**
     * The attributes that are mass assignable.
     *
     * @var array
     */


    protected $casts = [
        'viewed' => 'integer',
        'verified' => 'integer',
        'remember_token' => 'integer',
        'password_issued_at' => 'datetime',
        'otp_sent_at' => 'datetime',
    ];


    protected $fillable = ['name', 'email', 'password', 'password_issued_at', 'code', 'otp_sent_at',
        'default_address', 'phone', 'verified', 'remember_token', 'facebook_id', 'google_id', 'viewed', 'fcm_token'
    ];

    /**
     * The attributes that should be hidden for arrays.
     *
     * @var array
     */
    protected $hidden = ['password', 'remember_token'];

    public function fcmTokens()
    {
        return $this->hasMany(UserFcmToken::class, 'user_id', 'id');
    }

    /**
     * Все FCM-токены пользователя (мульти-устройство) + legacy users.fcm_token.
     *
     * @return array<int, string>
     */
    public function allFcmTokens(): array
    {
        $tokens = $this->fcmTokens()
            ->whereNotNull('fcm_token')
            ->where('fcm_token', '!=', '')
            ->pluck('fcm_token')
            ->all();

        if (!empty($this->fcm_token)) {
            $tokens[] = $this->fcm_token;
        }

        return array_values(array_unique(array_filter($tokens)));
    }

    public static function isPlaceholderEmail(?string $email): bool
    {
        return is_string($email) && str_ends_with($email, '@phone.ssboss.local');
    }

    public static function publicEmail(?string $email): string
    {
        if (!$email || self::isPlaceholderEmail($email)) {
            return '';
        }
        return $email;
    }
}
