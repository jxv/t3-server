module T3.GameCallbacks.Monad
  ( Env(..)
  , Callbacks(..)
  , GameCallbacks
  , runIO
  ) where

import qualified Control.Concurrent as IO
import qualified Control.Monad.STM as IO
import Control.Concurrent.Async (race)
import Control.Monad.Trans (lift)
import Control.Monad.Trans.Maybe (MaybeT(..))
import Control.Monad.State (StateT(..), MonadState(..), gets, evalStateT)
import Control.Monad.Reader (ReaderT(..), MonadReader(..), asks)
import Control.Monad.IO.Class (MonadIO(..))
import Data.Functor (void)

import T3.Core (Loc, Action, Board, Result, XO(..), emptyBoard)

import T3.Game.Monad (GameT, runGameT)
import T3.Game.Control (Control(..))
import T3.Game.HasBoard (HasBoard(..))
import T3.Game.BoardManager (BoardManager(..))

import T3.GameCallbacks.Types

import T3.GameCallbacks.BoardManager
import T3.GameCallbacks.Communicator
import T3.GameCallbacks.Console
import T3.GameCallbacks.Control
import T3.GameCallbacks.Finalizer
import T3.GameCallbacks.HasActions
import T3.GameCallbacks.HasTimeoutLimit
import T3.GameCallbacks.OnTimeout
import T3.GameCallbacks.Stoppable
import T3.GameCallbacks.Transmitter

import T3.GameCallbacks.Milliseconds (Milliseconds(..), delay)

newtype GameCallbacks a = GameCallbacks { unGameCallbacks :: MaybeT (ReaderT (Env IO) (StateT [Action] (GameT IO))) a }
  deriving
  ( Functor
  , Applicative
  , Monad
  , MonadIO
  , MonadReader (Env IO)
  , MonadState [Action]
  )

data Env m = Env
  { _callbacks :: XO -> Callbacks m
  , _timeoutLimit :: Maybe Milliseconds
  , _finalize :: [Action] -> Board -> Result -> m ()
  }

data Callbacks m = Callbacks
  { _callbacksRecv :: m Loc
  , _callbacksSend :: Step -> m ()
  }

go :: GameCallbacks a -> Env IO -> [Action] -> Board -> IO (Maybe a, [Action])
go (GameCallbacks m) env dat board = runGameT (runStateT (runReaderT (runMaybeT m) env) []) board

runIO :: GameCallbacks a -> Env IO -> IO ()
runIO gameCallbacks env = void $ go gameCallbacks env [] emptyBoard

instance Control GameCallbacks where
  move = move'
  forfeit = forfeit'
  end = end'
  tie = tie'

instance BoardManager GameCallbacks where
  isOpenLoc = isOpenLoc'
  insertAtLoc = insertAtLoc'
  getResult = getResult'

instance Communicator GameCallbacks where
  sendGameState = sendGameState'
  recvAction = recvAction'
  sendFinal = sendFinal'
  tally = tally'
  updateBoard = updateBoard'
  logAction = logAction'

instance Stoppable GameCallbacks where
  stop = GameCallbacks . MaybeT $ return Nothing

instance HasActions GameCallbacks where
  getActions = get
  putActions = put

instance Transmitter GameCallbacks where
  sendStep xo step = asks (_callbacksSend . flip _callbacks xo) >>= \send -> liftIO $ send step
  recvLoc xo = asks (_callbacksRecv . flip _callbacks xo) >>= \recv -> liftIO recv

instance Finalizer GameCallbacks where
  finalize actions board result = asks _finalize >>= \f -> liftIO $ f actions board result

instance OnTimeout GameCallbacks where
  onTimeout gameCallbacks ms = do
    env <- ask
    actions <- get
    board <- getBoard
    eitherOfMaybeAndData <- liftIO $ race (liftIO $ delay ms) (liftIO $ go gameCallbacks env actions board)
    case eitherOfMaybeAndData of
      Left _ -> return Nothing
      Right (maybeA, actions') -> do
        put actions'
        return maybeA

instance HasTimeoutLimit GameCallbacks where
  getTimeoutLimit = asks _timeoutLimit

instance Console GameCallbacks where
  printStdout = printStdout'

instance HasBoard GameCallbacks where
  getBoard = liftGameIO getBoard
  putBoard = liftGameIO . putBoard

liftGameIO :: GameT IO a -> GameCallbacks a
liftGameIO = GameCallbacks . lift . lift . lift