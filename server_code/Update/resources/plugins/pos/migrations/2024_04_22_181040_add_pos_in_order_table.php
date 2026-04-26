<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class AddPosInOrderTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('orders', function (Blueprint $table) {

            $table->integer('order_method')->nullable()->change();
            $table->integer('pos_order_id')->unsigned()->nullable();
            $table->unsignedBigInteger('user_address_id')->nullable()->change();

            $table->foreign('pos_order_id')
                ->references('id')
                ->on('pos_orders');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {

        if (Schema::hasColumn('orders', 'pos_order_id'))
        {
            Schema::table('orders', function (Blueprint $table) {

                $table->dropForeign('orders_pos_order_id_foreign');
                $table->dropColumn('pos_order_id');
            });
        }


    }
}
