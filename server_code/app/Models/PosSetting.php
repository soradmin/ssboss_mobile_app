<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PosSetting extends Model
{
    use HasFactory;


    protected $casts = [
        'is_default' => 'integer'
    ];

    protected $fillable = [
        'width', 'image', 'address', 'footer_text', 'header_text', 'is_default', 'admin_id'
    ];

    protected $hidden = [
        'admin_id'
    ];



}
