<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class FeatureWysiwygImage extends Model
{
    use HasFactory;


    protected $fillable = [
        'site_feature_id', 'image'
    ];


}
