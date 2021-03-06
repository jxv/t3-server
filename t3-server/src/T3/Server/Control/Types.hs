{-# LANGUAGE TemplateHaskell #-}
module T3.Server.Control.Types
  ( Env(..)
  , HasEnv(..)
  , AppHandler(..)
  ) where

import Control.Monad (mzero)
import Control.Lens hiding ((.=))
import Control.Monad.IO.Class (MonadIO)
import Control.Monad.Reader
import Control.Monad.Except
import Data.Text (Text)
import Data.String (IsString)
import Data.Aeson (ToJSON(..), FromJSON(..), (.:), Value(..), (.=), object)
import Servant

import T3.Server.Types

data Env = Env
  { _envPort :: !Int
  , _envPracticeLobbyObject :: !LobbyObject
  , _envArenaLobbyObject :: !LobbyObject
  , _envGamesObject :: !GamesObject
  , _envResultsObject :: !ResultsObject
  , _envRegistryObject :: !RegistryObject
  }

newtype AppHandler a = AppHandler { runHandler :: ReaderT Env (ExceptT ServantErr IO) a }
  deriving (Functor, Applicative, Monad, MonadReader Env, MonadError ServantErr, MonadIO)

makeClassy ''Env
