<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class UpdateShippingPlacesTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('shipping_places', function (Blueprint $table) {
            $table->string('pickup_phone')->nullable();
            $table->string('pickup_address_line_1')->nullable();
            $table->string('pickup_address_line_2')->nullable();
            $table->string('pickup_zip')->nullable();
            $table->string('pickup_state')->nullable();
            $table->string('pickup_city')->nullable();
            $table->string('pickup_country')->nullable();
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('shipping_places', function (Blueprint $table) {
            $table->dropColumn('pickup_phone');
            $table->dropColumn('pickup_address_line_1');
            $table->dropColumn('pickup_address_line_2');
            $table->dropColumn('pickup_zip');
            $table->dropColumn('pickup_state');
            $table->dropColumn('pickup_city');
            $table->dropColumn('pickup_country');
        });
    }
}
