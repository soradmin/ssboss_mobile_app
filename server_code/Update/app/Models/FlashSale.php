<?php

namespace App\Models;

use Illuminate\Database\Eloquent\Factories\HasFactory;
use Illuminate\Database\Eloquent\Model;
use Illuminate\Support\Facades\Config;

class FlashSale extends Model
{
    use HasFactory;

    protected $fillable = [
        'title', 'start_time', 'end_time', 'status', 'admin_id'
    ];

    protected $hidden = [
        'admin_id'
    ];


    public function public_products()
    {
        return $this->hasMany(FlashSaleProduct::class, 'flash_sale_id', 'id')
            ->whereHas('product', function ($query) {
                $query->where('status', Config::get('constants.status.PUBLIC'));
            })
            ->with(['product' => function ($query) {
                $query->select('id', 'slug', 'title', 'badge', 'selling', 'offered', 'image', 'review_count', 'rating');
            }]);
    }


    public function products()
    {
        return $this->hasMany(FlashSaleProduct::class, 'flash_sale_id', 'id');
    }
}
