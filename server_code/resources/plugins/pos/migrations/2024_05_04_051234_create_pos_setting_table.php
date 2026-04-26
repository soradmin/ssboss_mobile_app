<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreatePosSettingTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('pos_settings', function (Blueprint $table) {
            $table->increments('id');
            $table->timestamps();

            $table->integer('width')->default(300);
            $table->string('image')->nullable();
            $table->text('address')->nullable();
            $table->text('header_text')->nullable();
            $table->text('footer_text')->nullable();
            $table->boolean('is_default')->nullable();

            $table->integer('admin_id')->unsigned()->nullable();

            $table->foreign('admin_id')
                ->references('id')
                ->on('admins');

        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('pos_settings');
    }
}
