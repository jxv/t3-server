{-# LANGUAGE DataKinds #-}
{-# LANGUAGE TypeOperators #-}
{-# LANGUAGE OverloadedStrings #-}
module T3.Server.Control
  ( main
  ) where

import Control.Monad (mzero)
import Control.Monad.IO.Class (MonadIO)
import Data.Aeson (ToJSON(..), FromJSON(..), (.:), Value(..), (.=), object)
import Data.Map (fromList)
import Data.Text (Text)
import Network.Wai (Application)
import Network.Wai.Handler.Warp (run)
import Servant

import T3.Server.Types

data RegisterReq = RegisterReq
  { _registerReqName :: Text
  } deriving (Show, Eq)

data Creds = Creds
  { _credsName :: Text
  , _credsKey :: Text
  } deriving (Show, Eq)

data RegisterResp = RegisterResp
  { _registerRespCreds :: Creds
  } deriving (Show, Eq)

instance FromJSON RegisterReq where
  parseJSON (Object v) = RegisterReq <$> (v .: "name")
  parseJSON _ = mzero

instance ToJSON Creds where
  toJSON (Creds name key) = object ["name" .= name, "key" .= key]

instance ToJSON RegisterResp where
  toJSON (RegisterResp creds) = object ["creds" .= creds]

type Register = "register" :> ReqBody '[JSON] RegisterReq :> Post '[JSON] RegisterResp

type API = Register

register :: Monad m => RegisterReq -> m RegisterResp
register = undefined

server :: Server API
server = register

application :: Application
application = serve (Proxy :: Proxy API) server

main :: IO ()
main = run 8080 application
