<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

class DeleteColumnProductsTable extends Migration
{
    /**
     * Run the migrations.
     *
     * @return void
     */
    public function up()
    {
        Schema::table('products', function (Blueprint $table) {

            /*$table->dropForeign('products_category_id_foreign');
            $table->dropColumn('category_id');
            $table->dropColumn('subcategory_id');*/
        });
    }

    /**
     * Reverse the migrations.
     *
     * @return void
     */
    public function down()
    {
        Schema::table('products', function (Blueprint $table) {
           /* $table->bigInteger('category_id')->unsigned()->default(0);
            $table->integer('subcategory_id')->nullable();*/
        });
    }
}
