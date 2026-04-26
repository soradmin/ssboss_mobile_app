<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Config;

class Category extends Model
{
    use HasFactory;


    protected $fillable = [
        'title', 'image', 'status', 'admin_id', 'slug', 'meta_title', 'meta_description', 'meta_keywords',
        'parent', 'in_footer'
    ];

    protected $hidden = [
        'admin_id'
    ];

    public function parent_data()
    {
        return $this->belongsTo(Category::class, 'parent');
    }


    public function single_parent()
    {
        return $this->hasOne(Category::class, 'parent');
    }

    public function parentRecursive()
    {
        return $this->parent_data()->with('parentRecursive', 'languages');
    }

    public function languages()
    {
        return $this->hasMany(CategoryLang::class, 'category_id', 'id');
    }


    public function translations()
    {
        return $this->hasOne(CategoryLang::class, 'category_id');
    }



    public function children()
    {
        return $this->hasMany(Category::class, 'parent');
    }

    public function child()
    {
        return $this->hasMany(Category::class, 'parent')->with('child');
    }

    public function in_footer_child()
    {
        return $this->hasMany(Category::class, 'parent')
            ->with('in_footer_child')
            ->where('status', Config::get('constants.status.PUBLIC'))
            ->where('in_footer', Config::get('constants.status.PUBLIC'))
            ->select(['id', 'title', 'slug', 'parent']);
    }

    public function product_categories()
    {
        return $this->hasMany(ProductCategory::class, 'category_id', 'id');
    }


    public function public_sub_categories()
    {
        return $this->hasMany(SubCategory::class, 'category_id', 'id')
            ->where('status', Config::get('constants.status.PUBLIC'))
            ->select('id','title', 'slug', 'category_id');
    }

    public function sub_categories()
    {
        return $this->hasMany(SubCategory::class, 'category_id', 'id');
    }



}
