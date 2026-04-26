<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Config;

class Product extends Model
{
    use HasFactory;

    protected $attributes = [
        'category_id' => 0,
    ];

    protected $casts = [
        'purchased' => 'float',
        'offered' => 'float',
        'selling' => 'float',
        'review_count' => 'integer',
        'rating' => 'integer',
    ];



    protected $fillable = [
        'id', 'title', 'purchased', 'selling', 'offered', 'image', 'unit', 'video', 'video_thumb', 'badge',
        'status', 'admin_id', 'subcategory_id', 'category_id', 'brand_id', 'warranty', 'refundable',
        'description', 'overview', 'tags', 'tax_rule_id', 'shipping_rule_id', 'meta_title', 'meta_description',
        'meta_keywords',
        'review_count', 'rating', 'bundle_deal_id', 'slug'
    ];

    protected $hidden = [];


    public function flash_sale_product()
    {
        return $this->hasMany(FlashSaleProduct::class, 'product_id', 'id')
            ->with('flash_sale');
    }


    public function tax_rules()
    {
        return $this->hasOne(TaxRules::class, 'id', 'tax_rule_id');
    }


    public function category()
    {
        return $this->hasOne(Category::class, 'id', 'category_id')->select(['id', 'title', 'slug']);
    }


    public function product_categories()
    {
        return $this->hasMany(ProductCategory::class, 'product_id', 'id')
            ->orderBy('primary', 'DESC');
    }



    public function shipping_rule()
    {
        return $this->hasOne(ShippingRule::class, 'id', 'shipping_rule_id')
            ->select(['id', 'title', 'single_price']);
    }


    public function product_collections()
    {
        return $this->hasMany(CollectionWithProduct::class, 'product_id', 'id')
            ->select(['id', 'product_id', 'product_collection_id']);
    }


    public function product_inventories()
    {
        return $this->hasMany(UpdatedInventory::class, 'product_id', 'id');
    }


    public function product_images()
    {
        return $this->hasMany(ProductImage::class, 'product_id', 'id');
    }


    public function product_image_names()
    {
        return $this->hasMany(ProductImage::class, 'product_id', 'id');
    }

    public function store()
    {
        return $this->hasOne(Store::class, 'admin_id', 'admin_id');
    }


    public function bundle_deal()
    {
        return $this->hasOne(BundleDeal::class, 'id', 'bundle_deal_id')
            ->select(['id', 'buy', 'free', 'title']);
    }


    public function brand()
    {
        return $this->hasOne(Brand::class, 'id', 'brand_id')
            ->select(['title', 'id']);
    }


    public function admin()
    {
        return $this->hasOne(Admin::class, 'id', 'admin_id');
    }

}
