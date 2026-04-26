<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PosSettingLang extends Model
{
    use HasFactory;

    protected $fillable = [
        'pos_setting_id', 'address', 'header_text', 'footer_text', 'lang'
    ];
}
