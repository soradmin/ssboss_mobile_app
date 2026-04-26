<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;

class ShippingPlace extends Model
{
    use HasFactory;

    protected $fillable = [
        'id', 'country', 'state', 'price', 'pickup_price',
        'pickup_point', 'shipping_rule_id', 'admin_id' , 'day_needed',
        'pickup_phone', 'pickup_address_line_1', 'pickup_address_line_2', 'pickup_zip',
        'pickup_state', 'pickup_city', 'pickup_country'
    ];

    protected $hidden = [
        'admin_id',  'created_at',  'updated_at'
    ];

    public function shipping_rule()
    {
        return $this->hasOne(ShippingRule::class, 'id', 'shipping_rule_id');
    }

}
