<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class SiteFeatureLang extends Model
{
    use HasFactory;


    protected $fillable = [
        'site_feature_id', 'detail', 'lang'
    ];
}
