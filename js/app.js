(function () {
  "use strict";

  var ROW_H = 58;
  var LUNCH_H = 26;
  var WD = ["一", "二", "三", "四", "五", "六", "日"];
  var state = null; // { data, weekIndex, panels[], scrollTops[] }

  var strip = document.getElementById("weekStrip");
  var prevBtn = document.getElementById("prevBtn");
  var nextBtn = document.getElementById("nextBtn");
  var todayBtn = document.getElementById("todayBtn");
  var weekLabel = document.getElementById("weekLabel");
  var weekDates = document.getElementById("weekDates");
  var monthTitle = document.getElementById("monthTitle");
  var termLabel = document.getElementById("termLabel");
  var emptyTip = document.getElementById("emptyTip");

  var sheet = document.getElementById("sheet");
  var sheetCourse = document.getElementById("sheetCourse");
  var detailRows = document.getElementById("detailRows");
  document.getElementById("sheetBackdrop").addEventListener("click", closeSheet);
  document.getElementById("sheetClose").addEventListener("click", closeSheet);

  function pad(n) {
    return n < 10 ? "0" + n : String(n);
  }

  function parseDate(s) {
    var p = s.split("-");
    return new Date(+p[0], +p[1] - 1, +p[2]);
  }

  function fmtCn(d) {
    return d.getMonth() + 1 + "月" + d.getDate() + "日";
  }

  function todayStr() {
    var d = new Date();
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
  }

  function build() {
    var data = state.data;
    var rowH = ROW_H;
    var lunchTop = 5 * rowH;
    var totalH = lunchTop + LUNCH_H + (data.periods.length - 5) * rowH;
    var byDate = {};
    data.events.forEach(function (ev) {
      (byDate[ev.date] = byDate[ev.date] || []).push(ev);
    });
    var today = todayStr();
    var fragment = document.createDocumentFragment();
    state.panels = [];

    data.weeks.forEach(function (wk, wIdx) {
      var panel = document.createElement("section");
      panel.className = "week-panel";
      panel.dataset.week = wk.week;

      var bar = document.createElement("div");
      bar.className = "week-bar";
      var dates = [];
      var monday = parseDate(wk.monday);

      for (var i = 0; i < 7; i++) {
        var d = new Date(monday.getFullYear(), monday.getMonth(), monday.getDate() + i);
        var ds = d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
        dates.push(ds);
        var cell = document.createElement("div");
        cell.className = "day-head" + (ds === today ? " today" : "");
        var wd = document.createElement("span");
        wd.className = "wd";
        wd.textContent = WD[i];
        var dnum = document.createElement("span");
        dnum.className = "d";
        dnum.textContent = String(d.getDate());
        cell.appendChild(wd);
        cell.appendChild(dnum);
        bar.appendChild(cell);
      }

      var scroller = document.createElement("div");
      scroller.className = "week-scroll";
      var grid = document.createElement("div");
      grid.className = "grid-wrap";
      grid.style.height = totalH + "px";

      var timeCol = document.createElement("div");
      timeCol.className = "time-col";
      timeCol.style.height = totalH + "px";
      data.periods.forEach(function (p, idx) {
        var label = document.createElement("div");
        label.className = "period-label";
        label.style.top = periodY(idx + 1, rowH) + "px";
        label.style.height = rowH + "px";
        var b = document.createElement("b");
        b.textContent = String(idx + 1);
        var t = document.createElement("span");
        t.textContent = p.start;
        label.appendChild(b);
        label.appendChild(t);
        timeCol.appendChild(label);
      });
      var lunch = document.createElement("div");
      lunch.className = "lunch-line";
      lunch.style.top = lunchTop + "px";
      lunch.textContent = "午休";
      timeCol.appendChild(lunch);

      grid.appendChild(timeCol);

      var dayCols = [];
      for (var j = 0; j < 7; j++) {
        var col = document.createElement("div");
        col.className = "day-col";
        var lines = document.createElement("div");
        lines.className = "row-lines";
        lines.style.background =
          "repeating-linear-gradient(to bottom, transparent 0, transparent " +
          (rowH - 0.5) + "px, rgba(28,27,31,.08) " + (rowH - 0.5) + "px, rgba(28,27,31,.08) " + rowH + "px) 0 0 / 100% " + lunchTop + "px no-repeat," +
          "repeating-linear-gradient(to bottom, transparent 0, transparent " +
          (rowH - 0.5) + "px, rgba(28,27,31,.08) " + (rowH - 0.5) + "px, rgba(28,27,31,.08) " + rowH + "px) 0 " + (lunchTop + LUNCH_H) + "px / 100% " + (totalH - lunchTop - LUNCH_H) + "px no-repeat";
        col.appendChild(lines);
        var lunchBand = document.createElement("div");
        lunchBand.className = "lunch-band";
        lunchBand.style.top = lunchTop + "px";
        col.appendChild(lunchBand);
        var evLayer = document.createElement("div");
        evLayer.className = "events";
        (byDate[dates[j]] || []).forEach(function (ev) {
          var block = document.createElement("div");
          block.className = "event";
          block.style.top = periodY(ev.p0, rowH) + 2 + "px";
          block.style.height = ev.count * rowH - 6 + "px";
          block.style.background = colorOf(ev.code || ev.course, "bg");

          var name = document.createElement("span");
          name.className = "name";
          name.textContent = ev.course;
          var place = document.createElement("span");
          place.className = "place";
          place.textContent = shortRoom(ev.room);
          block.appendChild(name);
          if (ev.count > 1 || shortRoom(ev.room)) block.appendChild(place);
          block.addEventListener("click", function () { openSheet(ev); });
          evLayer.appendChild(block);
        });
        col.appendChild(evLayer);
        grid.appendChild(col);
        dayCols.push(col);
      }

      scroller.appendChild(grid);
      panel.appendChild(bar);
      panel.appendChild(scroller);
      fragment.appendChild(panel);
      state.panels.push({ panel: panel, scroller: scroller, scrollTop: 0, monday: wk.monday });
    });

    strip.innerHTML = "";
    strip.appendChild(fragment);
    termLabel.textContent = data.grade || data.term || "";
    setWeek(0, false);
    state.panels[0].scroller.scrollTop = 0;
    requestAnimationFrame(syncGlobalWeek);
  }

  function periodY(p, rowH) {
    return p <= 5 ? (p - 1) * rowH : 5 * rowH + LUNCH_H + (p - 6) * rowH;
  }

  function colorOf(code, mode) {
    var data = state.data;
    if (!data) return mode === "bg" ? "#e0e0e0" : "#333";
    var c = data.courses[code] || data.courses[Object.keys(data.courses)[0]];
    return mode === "bg" ? c.color : "#1c1b1f";
  }

  function shortRoom(room) {
    if (!room) return "";
    return String(room).replace(/^浦东-/, "").replace(/^医学院-/, "");
  }

  function setWeek(idx, animate) {
    if (!state || !state.panels.length) return;
    idx = Math.max(0, Math.min(state.panels.length - 1, idx));
    var prev = state.panels[state.weekIndex];
    if (prev && prev.scroller) prev.scrollTop = prev.scroller.scrollTop;
    state.weekIndex = idx;
    var panel = state.panels[idx];
    var w = panel.panel.clientWidth || document.documentElement.clientWidth;
    strip.scrollTo({ left: idx * w, behavior: animate ? "smooth" : "auto" });
    if (panel.scroller) panel.scroller.scrollTop = panel.scrollTop || 0;
    syncGlobalWeek();
  }

  function syncGlobalWeek() {
    if (!state || !state.panels.length) return;
    var wk = state.data.weeks[state.weekIndex];
    if (!wk) return;
    var d = parseDate(wk.monday);
    monthTitle.textContent = (d.getMonth() + 1) + "月";
    weekLabel.textContent = "第 " + wk.week + " 周";
    var end = new Date(d.getFullYear(), d.getMonth(), d.getDate() + 6);
    weekDates.textContent = fmtCn(d) + " – " + fmtCn(end);
  }

  function onScroll() {
    if (!state || !state.panels.length) return;
    var width = strip.clientWidth || document.documentElement.clientWidth;
    if (!width) return;
    var idx = Math.round(strip.scrollLeft / width);
    if (idx !== state.weekIndex) {
      var prev = state.panels[state.weekIndex];
      if (prev) prev.scrollTop = prev.scroller.scrollTop;
      state.weekIndex = idx;
      var cur = state.panels[idx];
      if (cur) cur.scroller.scrollTop = cur.scrollTop || 0;
      syncGlobalWeek();
    }
  }

  var scrollTicking = false;
  strip.addEventListener("scroll", function () {
    if (!scrollTicking) {
      scrollTicking = true;
      requestAnimationFrame(function () {
        onScroll();
        scrollTicking = false;
      });
    }
  });

  prevBtn.addEventListener("click", function () {
    setWeek(state.weekIndex - 1, true);
  });
  nextBtn.addEventListener("click", function () {
    setWeek(state.weekIndex + 1, true);
  });

  todayBtn.addEventListener("click", function () {
    var t = todayStr();
    var data = state && state.data;
    if (!data) return;
    var idx = 0;
    for (var i = 0; i < data.weeks.length; i++) {
      var m = data.weeks[i].monday;
      var end = new Date(parseDate(m).getTime());
      end.setDate(end.getDate() + 6);
      if (t >= m && t <= endStr(end)) { idx = i; break; }
    }
    setWeek(idx, true);
  });

  function endStr(d) {
    return d.getFullYear() + "-" + pad(d.getMonth() + 1) + "-" + pad(d.getDate());
  }

  function openSheet(ev) {
    if (!state) return;
    var c = state.data.courses[ev.code || ev.course];
    sheetCourse.innerHTML = "";
    var dot = document.createElement("span");
    dot.className = "course-dot";
    dot.style.background = c ? c.color : "#ccc";
    sheetCourse.appendChild(dot);
    sheetCourse.appendChild(document.createTextNode(ev.course));

    var rows = [
      ["课程代码", ev.code],
      ["课程类型", ev.type],
      ["上课班级", cleanClass(ev.className || ev.classCode)],
      ["教师", ev.teacher],
      ["上课时间", ev.courseText || periodText(ev)],
      ["上课地点", ev.room],
      ["课程内容", ev.content],
      ["备注", ev.bz]
    ];
    detailRows.innerHTML = "";
    rows.forEach(function (row) {
      if (!row[1] || !String(row[1]).trim()) return;
      var r = document.createElement("div");
      r.className = "detail-row";
      var k = document.createElement("span");
      k.className = "k";
      k.textContent = row[0];
      var v = document.createElement("span");
      v.className = "v";
      v.textContent = row[1];
      r.appendChild(k);
      r.appendChild(v);
      detailRows.appendChild(r);
    });
    sheet.hidden = false;
    document.body.style.overflow = "hidden";
  }

  function cleanClass(s) {
    if (!s) return "";
    return String(s).replace(/\s+/g, " ").trim();
  }

  function periodText(ev) {
    if (!ev.p0) return "";
    var end = ev.p0 + ev.count - 1;
    var dayName = WD[ev.dow - 1];
    var ampm = end <= 5 ? "上午" : end >= 6 && end <= 9 ? "下午" : "晚上";
    return "星期" + dayName + " " + ampm + "第" + ev.p0 + "-" + end + "节";
  }

  function closeSheet() {
    if (!sheet.hidden) {
      sheet.hidden = true;
      document.body.style.overflow = "";
    }
  }

  function load() {
    emptyTip.hidden = false;
    fetch("data/schedule.json", { cache: "no-cache" })
      .then(function (r) {
        if (!r.ok) throw new Error("HTTP " + r.status);
        return r.json();
      })
      .then(function (data) {
        state = { data: data, weekIndex: 0, panels: [] };
        emptyTip.hidden = true;
        build();
      })
      .catch(function (err) {
        emptyTip.hidden = false;
        emptyTip.textContent = "课表数据读取失败：" + err.message + "\n请用本地服务器打开（见使用说明）。";
        console.error(err);
      });
  }

  if ("serviceWorker" in navigator && location.protocol.indexOf("http") === 0) {
    window.addEventListener("load", function () {
      navigator.serviceWorker.register("sw.js").catch(function () {});
    });
  }

  load();
})();
