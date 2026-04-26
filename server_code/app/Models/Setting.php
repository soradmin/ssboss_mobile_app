<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Setting extends Model
{
    use HasFactory;

    protected $casts = [
        'facebook_login' => 'integer',
        'google_login' => 'integer',
        'attach_pdf' => 'integer',
        'translate_pdf' => 'integer',
        'guest_checkout' => 'integer',
        'send_seller_email' => 'integer',
        'enable_ga' => 'integer',
        'enable_pixel' => 'integer',
        'vendor_registration' => 'integer',
        'cookie_banner' => 'integer'
    ];

    protected $fillable = [
        'currency', 'currency_icon', 'currency_position', 'phone', 'address_1' , 'email',
        'address_2', 'city', 'state', 'zip', 'country', 'admin_id', 'decimal_format', 'google_login',
        'facebook_login', 'attach_pdf', 'guest_checkout', 'send_seller_email', 'enable_ga', 'ga_id',
        'vendor_registration', 'cookie_banner',
        'enable_pixel', 'pixel_id',
        'default_state', 'default_country',
        'translate_pdf'
    ];

    protected $hidden = [
        'admin_id'
    ];
}
