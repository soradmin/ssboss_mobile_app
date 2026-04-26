<?php

use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;

$app =  Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        web: __DIR__.'/../routes/web.php',
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        health: '/up',
    )
    ->withMiddleware(function (Middleware $middleware) {
        // $middleware->append(\Illuminate\Http\Middleware\HandleCors::class);
        $middleware->alias([
            'scope' => \App\Http\Middleware\CheckForAllScopes::class,
            'social' => \App\Http\Middleware\SocialMiddleware::class
        ]);

    })
    ->withExceptions(function (Exceptions $exceptions) {

    })
    ->create();

//$app->register(Illuminate\Database\DatabaseServiceProvider::class);

return $app;
