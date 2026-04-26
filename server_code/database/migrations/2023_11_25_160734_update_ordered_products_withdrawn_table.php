<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Facades\Config;

class UpdateOrderedProductsWithdrawnTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('ordered_products', function (Blueprint $table) {
            $table->integer('withdrawn')->nullable()->default(Config::get('constants.withdrawn.NO'));

            $table->integer('withdrawal_id')->nullable()->unsigned();
            $table->foreign('withdrawal_id')
                ->references('id')
                ->on('withdrawals');


        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('ordered_products', function (Blueprint $table) {
            $table->dropColumn('withdrawn');
            $table->dropColumn('withdrawal_id');
        });
    }
}
