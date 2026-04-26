<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreatePosSettingLangTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('pos_setting_langs', function (Blueprint $table) {
            $table->increments('id');
            $table->timestamps();

            $table->text('address')->nullable();
            $table->text('header_text')->nullable();
            $table->text('footer_text')->nullable();

            $table->text('lang');

            $table->integer('pos_setting_id')->unsigned();

            $table->foreign('pos_setting_id')
                ->references('id')
                ->on('pos_settings');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('pos_setting_langs');
    }
}
