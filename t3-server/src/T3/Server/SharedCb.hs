module T3.Server.SharedCb
  ( newRegistryCb'
  , newGamesCb'
  ) where

import qualified Data.Map as Map
import Control.Monad.IO.Class (MonadIO(liftIO))
import Control.Concurrent.STM

import T3.Server.Gen (genUserId', genHashCode')
import T3.Server.Types

type UserRec = (Name, Token)
type UserMap = Map.Map UserId UserRec

newRegistryCb' :: MonadIO m => m RegistryCb
newRegistryCb' = do
  hc <- genHashCode'
  w <- liftIO $ newTVarIO Map.empty
  return RegistryCb
    { _registryCbHashCode = hc
    , _registryCbInsertUser = insertUser w
    , _registryCbGetUserById = getUserById w
    }

insertUser :: TVar UserMap -> UserRec -> IO (Maybe UserId)
insertUser w rec = do
  userId <- genUserId'
  atomically $ do
    m <- readTVar w
    if Map.notMember userId m
      then do
        writeTVar w (Map.insert userId rec m)
        return (Just userId)
      else return Nothing

getUserById :: TVar UserMap -> UserId -> IO (Maybe UserRec)
getUserById w i = atomically $ do
  m <- readTVar w
  return $ Map.lookup i m

type GameMap = Map.Map GameId ThreadCb

newGamesCb' :: MonadIO m => m GamesCb
newGamesCb' = do
  w <- liftIO $ newTVarIO Map.empty
  return GamesCb
    { _gamesCbInsertGame = insertGame w
    }

insertGame :: TVar GameMap -> (GameId, ThreadCb) -> IO ()
insertGame w (gameId, threadCb) = atomically $ modifyTVar w (Map.insert gameId threadCb)
