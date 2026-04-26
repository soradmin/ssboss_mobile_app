<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Plugin extends Model
{
    use HasFactory;

    protected $casts = [
        'active' => 'integer'
    ];

    protected $fillable = [
        'public_key', 'encrypt_key', 'encrypt_iv', 'secret_key', 'active', 'name'

    ];

}
