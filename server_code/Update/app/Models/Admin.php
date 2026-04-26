<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Foundation\Auth\User as Authenticatable;
use Illuminate\Notifications\Notifiable;
use Laravel\Passport\HasApiTokens;
use Spatie\Permission\Traits\HasRoles;

class Admin extends Authenticatable
{
    use HasFactory, Notifiable, HasApiTokens, HasRoles;


    protected $casts = [
        'remember_token' => 'integer',
        'verified' => 'integer',
        'active' => 'integer',
        'viewed' => 'integer'
    ];

    protected $fillable = [
        'name',
        'username',
        'email',
        'commission',
        'password',
        'code',
        'verified',
        'viewed',
        'active'
    ];

    protected $hidden = [
        'password',
        'remember_token',
    ];

}
