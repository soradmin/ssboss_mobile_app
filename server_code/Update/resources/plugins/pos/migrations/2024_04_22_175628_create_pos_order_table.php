<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Config;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\DB;

class CreatePosOrderTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('pos_orders', function (Blueprint $table) {
            $table->increments('id');
            $table->timestamps();

            $table->integer('payment_method')->default(Config::get('constants.posMethod.CASH'));
            $table->integer('admin_id')->unsigned()->nullable();
            $table->integer('order_id')->unsigned();

            $table->string('offline_trans_id')->nullable();
            $table->string('offline_payment_method')->nullable();
            $table->string('offline_payment_proof')->nullable();

            $table->foreign('admin_id')
                ->references('id')
                ->on('admins');

            $table->foreign('order_id')
                ->references('id')
                ->on('orders');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('pos_orders');
    }
}
