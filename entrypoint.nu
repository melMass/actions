#!/usr/bin/env nu
use toolkit.nu

def add [x:int, y:int] {
  $x + $y
}
def greet [name:string] {
  echo $"Hello, {$name}!"
}

export def main [script?:string] {
  print $"(ansi red_bold)Running Nushell(ansi reset)"
  # print $script
  # print (toolkit get_root)
  print $env
  # nu -
  # nu -c "${combined_script}"
    
}
