<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class OrderedProduct extends Model
{
    use HasFactory;


    protected $casts = [
        'bundle_offer' => 'integer',
        'quantity' => 'integer',
        'withdrawal_id' => 'integer',
        'withdrawn' => 'integer'
    ];

    protected $fillable = [
        'product_id', 'inventory_id', 'quantity', 'shipping_place_id', 'shipping_type', 'purchased', 'commission',
        'commission_amount', 'tax_price',
        'selling', 'shipping_price', 'bundle_offer', 'order_id', 'withdrawn', 'withdrawal_id'
    ];

    public function shipping_place()
    {
        return $this->hasOne(ShippingPlace::class, 'id', 'shipping_place_id');
    }

    public function product_inner()
    {
        return $this->hasOne(Product::class, 'id', 'product_id')
            ->select(['id', 'title', 'image', 'selling', 'offered', 'shipping_rule_id', 'admin_id', 'purchased']);
    }

    public function product()
    {
        return $this->hasOne(Product::class, 'id', 'product_id')
            ->select(['id', 'title', 'slug', 'image', 'selling', 'offered', 'shipping_rule_id',
                'bundle_deal_id', 'unit']);
    }


    public function product_with_admin()
    {
        return $this->hasOne(Product::class, 'id', 'product_id')
            ->select(['id', 'title', 'slug', 'image', 'selling', 'offered', 'shipping_rule_id',
                'admin_id', 'bundle_deal_id', 'unit']);
    }


    public function inventory_public()
    {
        return $this->hasOne(Inventory::class, 'id', 'inventory_id')
            ->select(['id', 'attributes']);
    }

    public function updated_inventory()
    {
        return $this->hasOne(UpdatedInventory::class, 'id', 'inventory_id');
    }

    public function product_images()
    {
        return $this->hasMany(ProductImageAttribute::class, 'product_id', 'product_id');
    }
}
