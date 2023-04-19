<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

class MyCommand extends Command
{
    /**
     * The name and signature of the console command.
     *
     * @var string
     */
    protected $signature = 'my:command';

    /**
     * The console command description.
     *
     * @var string
     */
    protected $description = 'My custom command';

    /**
     * Execute the console command.
     *
     * @return int
     */
    public function handle()
    {
        // Your custom command logic goes here
        return 0;
    }
}