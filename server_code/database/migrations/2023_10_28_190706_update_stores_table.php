<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class UpdateStoresTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('stores', function (Blueprint $table) {
            $table->boolean('whatsapp_btn')->default(true);
            $table->string('whatsapp_number')->nullable();
            $table->string('whatsapp_default_msg')->nullable();
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('stores', function (Blueprint $table) {
            $table->dropColumn('whatsapp_btn');
            $table->dropColumn('whatsapp_number');
            $table->dropColumn('whatsapp_default_msg');
        });
    }
}
