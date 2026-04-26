<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class UpdateSettingMiscellaneousTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('settings', function (Blueprint $table) {
            $table->boolean('attach_pdf')->default(true);
            $table->boolean('guest_checkout')->default(true);
            $table->boolean('send_seller_email')->default(false);
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('settings', function (Blueprint $table) {
            $table->dropColumn('guest_checkout');
            $table->dropColumn('attach_pdf');
            $table->dropColumn('send_seller_email');
        });
    }
}
