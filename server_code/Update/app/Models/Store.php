<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class Store extends Model
{
    use HasFactory;

    protected $casts = [
        'whatsapp_btn' => 'integer'
    ];

    protected $fillable = [
        'image', 'name', 'slug', 'admin_id', 'meta_title', 'meta_description', 'meta_keywords',
        'whatsapp_btn', 'whatsapp_number', 'whatsapp_default_msg'
    ];

    protected $hidden = [
        'admin_id'
    ];

}
