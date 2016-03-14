module T3.Server.Lobby where

import Prelude
import Control.Concurrent.STM
import System.Random
import Data.Maybe
import T3.Match

type Lobby = [(UserName, StartCallback)]

addUserToLobby :: TVar Lobby  -> UserName -> (StartCallback) -> IO ()
addUserToLobby lobby un cb = atomically $
  modifyTVar lobby (\lob -> if isJust (lookup un lob) then lob else (un, cb) : lob)

userPairFromLobby :: TVar Lobby -> IO (Maybe ((UserName, StartCallback), (UserName, StartCallback)))
userPairFromLobby lobby = do
  a <- randomIO
  b <- randomIO
  atomically $ do
    lob <- readTVar lobby
    let len = length lob
    if len < 2 then return Nothing else grabEm lob (mod a len) (mod b (len - 1))
  where
    grabEm lob i j = do
      let (x, lob') = grab lob i
      let (y, lob'') = grab lob' j
      writeTVar lobby lob''
      return $ Just (x, y)
    grab :: [a] -> Int -> (a, [a])
    grab xs idx = (xs !! idx, take idx xs ++ drop (idx + 1) xs)
