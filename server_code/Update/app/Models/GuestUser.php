<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class GuestUser extends Model
{
    use HasFactory;


    protected $casts = [
        'viewed' => 'integer'
    ];

    protected $fillable = [
        'name', 'email', 'user_token', 'default_address', 'viewed'
    ];
}
