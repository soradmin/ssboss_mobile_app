<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class AddPayfastPaymentTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->boolean('payfast_payment')->default(true)->nullable();
            $table->string('payfast_base_url')->nullable();
            $table->string('payfast_merchant_id')->nullable();
            $table->string('payfast_merchant_key')->nullable();
            $table->string('payfast_passphrase')->nullable();
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('payments', function (Blueprint $table) {
            $table->dropColumn('payfast_payment');
            $table->dropColumn('payfast_base_url');
            $table->dropColumn('payfast_merchant_id');
            $table->dropColumn('payfast_merchant_key');
            $table->dropColumn('payfast_passphrase');
        });
    }
}
