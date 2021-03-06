{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
module T3.Server.Control.Monad
  ( Env(..)
  , main
  ) where

import Control.Monad (mzero)
import Control.Monad.IO.Class (MonadIO)
import Control.Monad.Reader
import Control.Monad.Except
import Data.Map (fromList)
import Data.Text (Text)
import Network.Wai (Application)
import Network.Wai.Handler.Warp (run)
import Servant

import T3.Server.Types hiding (Result)
import T3.Server.Control.Types
import T3.Server.Control.Register (register)
import T3.Server.Control.Lobby (lobby, LobbyType(LobbyPractice, LobbyArena))
import T3.Server.Control.Play (play)
import T3.Server.Control.Result (result)

main :: MonadIO m => Env -> m ()
main env = liftIO $ run (_envPort env) (application env)

application :: Env -> Application
application env = serve (Proxy :: Proxy API) (server env)

server :: Env -> Server API
server env = enter (appToHandler env) serverT
  where
    appToHandler :: Env -> AppHandler :~> Handler
    appToHandler env = Nat (appToHandler' env)
      where
        appToHandler' :: forall a. Env -> AppHandler a -> Handler a
        appToHandler' env (AppHandler m) = runReaderT m env

type AppServer api = ServerT api AppHandler

type Register = "register" :> ReqBody '[JSON] RegisterReq :> Post '[JSON] RegisterResp
type PracticeLobby = "practice-lobby" :> ReqBody '[JSON] LobbyReq :> Post '[JSON] LobbyResp
type ArenaLobby = "lobby" :> ReqBody '[JSON] LobbyReq :> Post '[JSON] LobbyResp
type Play = "play" :> ReqBody '[JSON] PlayReq :> Post '[JSON] PlayResp
type Result = "result" :> ReqBody '[JSON] ResultReq :> Post '[JSON] ResultResp

type API =
  Register :<|>
  PracticeLobby :<|>
  ArenaLobby :<|>
  Play :<|>
  Result

serverT :: AppServer API
serverT =
  register :<|>
  lobby LobbyPractice :<|>
  lobby LobbyArena :<|>
  play :<|>
  result
