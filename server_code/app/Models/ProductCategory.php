<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ProductCategory extends Model
{
    use HasFactory;


    protected $casts = [
        'primary' => 'integer'
    ];


    protected $fillable = [
        'category_id', 'product_id', 'primary'
    ];



    public function category()
    {
        return $this->hasOne(Category::class, 'id', 'category_id');
    }

}
