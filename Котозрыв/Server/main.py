
import asyncio
import logging
from aiohttp import web
from routes import setup_routes
from websocket_handler import setup_websocket

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("kotozryv")


async def create_app() -> web.Application:
    app = web.Application()
    setup_routes(app)
    setup_websocket(app)
    return app


if __name__ == "__main__":
    logger.info("Запуск сервера Котозрыв на :8080")
    web.run_app(create_app(), host="0.0.0.0", port=8080)
