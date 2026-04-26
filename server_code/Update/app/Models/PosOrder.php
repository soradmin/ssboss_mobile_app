<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class PosOrder extends Model
{
    use HasFactory;

    protected $fillable = [
        'payment_method', 'admin_id', 'order_id', 'offline_trans_id', 'offline_payment_method',
        'offline_payment_proof'
    ];

    protected $hidden = [
        'admin_id'
    ];

    public function admin()
    {
        return $this->hasOne(Admin::class, 'id', 'admin_id');
    }

    public function order()
    {
        return $this->hasOne(Order::class, 'id', 'order_id');
    }

    public function ordered_products()
    {
        return $this->hasMany(OrderedProduct::class, 'order_id', 'id')
            ->select([ 'product_id', 'inventory_id', 'quantity', 'shipping_place_id', 'shipping_type',
                'selling', 'shipping_price', 'tax_price', 'bundle_offer', 'order_id']);
    }
}
