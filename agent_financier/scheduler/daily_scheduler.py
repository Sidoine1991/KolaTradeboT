#!/usr/bin/env python3
"""daily_scheduler.py – Planification du scan à 07:00."""
import logging
from apscheduler.schedulers.background import BackgroundScheduler
from apscheduler.triggers.cron import CronTrigger

logger = logging.getLogger(__name__)


class DailyScheduler:
    def __init__(self, hour=7, minute=0):
        self.hour = hour
        self.minute = minute
        self.scheduler = BackgroundScheduler()

    def schedule(self, callback):
        trigger = CronTrigger(hour=self.hour, minute=self.minute)
        self.scheduler.add_job(callback, trigger, id="daily_smc")
        logger.info("Scan planifié pour %02d:%02d", self.hour, self.minute)

    def start(self):
        self.scheduler.start()

    def stop(self):
        self.scheduler.shutdown()
