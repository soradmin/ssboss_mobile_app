<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class UpdateOrderedProductsTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('ordered_products', function (Blueprint $table) {
            $table->decimal('selling', 10, 2)->default(0)->change();
            $table->decimal('purchased', 10, 2)->default(0)->change();
            $table->decimal('tax_price', 10, 2)->default(0)->change();
            $table->decimal('commission', 10, 2)->default(0)->change();
            $table->decimal('commission_amount', 10, 2)->default(0)->change();
            $table->decimal('shipping_price', 10, 2)->default(0)->change();
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        //
    }
}
