<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class CustomScript extends Model
{
    use HasFactory;

    protected $casts = [
        'header_script' => 'integer',
        'body_script' => 'integer'
    ];


    protected $fillable = [
        'id', 'route_pattern', 'header_script', 'header_script_code',
        'body_script', 'body_script_code',
        'status'
    ];
}
