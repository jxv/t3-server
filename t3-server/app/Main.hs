module Main where

import qualified T3.Server.Main as Server (main)
import T3.Server.Main (runServer)

main :: IO ()
main = runServer Server.main
