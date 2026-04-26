<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class UpdateSettingCountryTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('settings', function (Blueprint $table) {
            $table->string('default_country')->nullable()->default('AF');
            $table->string('default_state')->nullable()->default('BDS');

            $table->boolean('translate_pdf')->default(false);
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
            $table->dropColumn('default_country');
            $table->dropColumn('default_state');
            $table->dropColumn('translate_pdf');
        });
    }
}
