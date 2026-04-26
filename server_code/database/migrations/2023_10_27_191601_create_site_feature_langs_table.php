<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class CreateSiteFeatureLangsTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::create('site_feature_langs', function (Blueprint $table) {
            $table->increments('id');
            $table->timestamps();

            $table->string('detail')->nullable();

            $table->text('lang');

            $table->unsignedInteger('site_feature_id');

            $table->foreign('site_feature_id')
                ->references('id')
                ->on('site_features');
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::dropIfExists('site_feature_langs');
    }
}
